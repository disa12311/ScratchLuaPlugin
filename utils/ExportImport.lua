--[[
    ExportImport.lua
    Export block program ra JSON string và import ngược lại.
    Dùng plugin:SetSetting để mô phỏng "file" vì Studio plugin
    không có file system API trực tiếp.

    Workflow:
    - Export: serialize → copy vào clipboard (qua TextBox trick)
    - Import: paste JSON từ một popup TextBox
--]]

local HttpService = game:GetService("HttpService")

local ExportImport = {}

local FORMAT_VERSION = "ScratchLua_Export_v1"

-- ─── Tạo JSON export string ───────────────────────────────────

function ExportImport.toJSON(placedBlocks, blockCounter)
    local blocks = {}
    for _, bd in ipairs(placedBlocks) do
        -- Sync inputs từ TextBox
        local inputs = {}
        if bd.frame then
            local inputsFrame = bd.frame:FindFirstChild("Inputs")
            if inputsFrame then
                for _, row in ipairs(inputsFrame:GetChildren()) do
                    if row:IsA("Frame") then
                        for _, child in ipairs(row:GetChildren()) do
                            if child:IsA("TextBox") then
                                local name = child.Name:gsub("^Input_", "")
                                inputs[name] = child.Text
                            end
                        end
                    end
                end
            end
        end
        for k, v in pairs(bd.inputs or {}) do
            if inputs[k] == nil then inputs[k] = v end
        end

        table.insert(blocks, {
            id       = bd.id,
            defId    = bd.defId,
            posX     = bd.frame and math.floor(bd.frame.Position.X.Offset) or 0,
            posY     = bd.frame and math.floor(bd.frame.Position.Y.Offset) or 0,
            inputs   = inputs,
            nextId   = bd.next   and bd.next.id   or nil,
            prevId   = bd.prev   and bd.prev.id   or nil,
            parentId = bd.parentId or nil,
        })
    end

    local payload = {
        format       = FORMAT_VERSION,
        blockCounter = blockCounter,
        blocks       = blocks,
        exportedAt   = os.time(),
    }

    local ok, json = pcall(HttpService.JSONEncode, HttpService, payload)
    return ok and json or nil
end

-- ─── Parse JSON import string ─────────────────────────────────

function ExportImport.fromJSON(jsonStr)
    if not jsonStr or jsonStr == "" then
        return nil, "JSON rỗng"
    end

    local ok, data = pcall(HttpService.JSONDecode, HttpService, jsonStr)
    if not ok then
        return nil, "JSON không hợp lệ: " .. tostring(data)
    end

    if type(data) ~= "table" then
        return nil, "Dữ liệu không phải table"
    end

    if data.format ~= FORMAT_VERSION then
        return nil, "Format không khớp (cần " .. FORMAT_VERSION .. ")"
    end

    if type(data.blocks) ~= "table" then
        return nil, "Thiếu trường blocks"
    end

    return data, nil
end

-- ─── Tạo popup Import Dialog trong widget ────────────────────
-- Trả về Frame (parent tự add vào widget)

function ExportImport.createImportDialog(onConfirm, onCancel)
    local overlay = Instance.new("Frame")
    overlay.Name = "ImportOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex = 100

    local dialog = Instance.new("Frame")
    dialog.Name = "Dialog"
    dialog.Size = UDim2.new(0, 440, 0, 280)
    dialog.Position = UDim2.new(0.5, -220, 0.5, -140)
    dialog.BackgroundColor3 = Color3.fromRGB(42, 42, 46)
    dialog.ZIndex = 101
    dialog.Parent = overlay

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = dialog

    local title = Instance.new("TextLabel")
    title.Text = "📥  Import Block Program"
    title.Size = UDim2.new(1, -16, 0, 32)
    title.Position = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(220, 220, 220)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = dialog

    local hint = Instance.new("TextLabel")
    hint.Text = "Paste JSON export vào đây:"
    hint.Size = UDim2.new(1, -16, 0, 20)
    hint.Position = UDim2.new(0, 8, 0, 42)
    hint.BackgroundTransparency = 1
    hint.TextColor3 = Color3.fromRGB(160, 160, 160)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 102
    hint.Parent = dialog

    local textBox = Instance.new("TextBox")
    textBox.Name = "JsonInput"
    textBox.Size = UDim2.new(1, -16, 0, 150)
    textBox.Position = UDim2.new(0, 8, 0, 64)
    textBox.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    textBox.TextColor3 = Color3.fromRGB(180, 220, 180)
    textBox.Font = Enum.Font.Code
    textBox.TextSize = 10
    textBox.MultiLine = true
    textBox.TextWrapped = true
    textBox.ClearTextOnFocus = false
    textBox.Text = ""
    textBox.PlaceholderText = '{"format":"ScratchLua_Export_v1", ...}'
    textBox.PlaceholderColor3 = Color3.fromRGB(80, 80, 80)
    textBox.ZIndex = 102
    local tb_c = Instance.new("UICorner")
    tb_c.CornerRadius = UDim.new(0, 4)
    tb_c.Parent = textBox
    textBox.Parent = dialog

    local errorLabel = Instance.new("TextLabel")
    errorLabel.Name = "ErrorLabel"
    errorLabel.Text = ""
    errorLabel.Size = UDim2.new(1, -16, 0, 16)
    errorLabel.Position = UDim2.new(0, 8, 0, 220)
    errorLabel.BackgroundTransparency = 1
    errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    errorLabel.Font = Enum.Font.Gotham
    errorLabel.TextSize = 10
    errorLabel.TextXAlignment = Enum.TextXAlignment.Left
    errorLabel.ZIndex = 102
    errorLabel.Parent = dialog

    -- Buttons
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Text = "Hủy"
    cancelBtn.Size = UDim2.new(0, 80, 0, 26)
    cancelBtn.Position = UDim2.new(1, -176, 0, 244)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    cancelBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    cancelBtn.Font = Enum.Font.GothamSemibold
    cancelBtn.TextSize = 12
    cancelBtn.ZIndex = 102
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 4); cc.Parent = cancelBtn
    cancelBtn.Parent = dialog

    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Text = "Import"
    confirmBtn.Size = UDim2.new(0, 80, 0, 26)
    confirmBtn.Position = UDim2.new(1, -88, 0, 244)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(67, 133, 245)
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.Font = Enum.Font.GothamSemibold
    confirmBtn.TextSize = 12
    confirmBtn.ZIndex = 102
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 4); fc.Parent = confirmBtn
    confirmBtn.Parent = dialog

    cancelBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        if onCancel then onCancel() end
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        local data, err = ExportImport.fromJSON(textBox.Text)
        if err then
            errorLabel.Text = "⚠ " .. err
        else
            overlay:Destroy()
            if onConfirm then onConfirm(data) end
        end
    end)

    return overlay
end

-- ─── Tạo Export Dialog (hiện JSON, cho phép copy) ─────────────

function ExportImport.createExportDialog(jsonStr, onClose)
    local overlay = Instance.new("Frame")
    overlay.Name = "ExportOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.ZIndex = 100

    local dialog = Instance.new("Frame")
    dialog.Name = "Dialog"
    dialog.Size = UDim2.new(0, 440, 0, 300)
    dialog.Position = UDim2.new(0.5, -220, 0.5, -150)
    dialog.BackgroundColor3 = Color3.fromRGB(42, 42, 46)
    dialog.ZIndex = 101
    dialog.Parent = overlay

    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = dialog

    local title = Instance.new("TextLabel")
    title.Text = "📤  Export Block Program"
    title.Size = UDim2.new(1, -16, 0, 32)
    title.Position = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(220, 220, 220)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = dialog

    local hint = Instance.new("TextLabel")
    hint.Text = "Copy JSON bên dưới để lưu chương trình:"
    hint.Size = UDim2.new(1, -16, 0, 20)
    hint.Position = UDim2.new(0, 8, 0, 42)
    hint.BackgroundTransparency = 1
    hint.TextColor3 = Color3.fromRGB(160, 160, 160)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 102
    hint.Parent = dialog

    -- TextBox hiển thị JSON (readonly trick: ClearTextOnFocus = false)
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -16, 0, 180)
    textBox.Position = UDim2.new(0, 8, 0, 64)
    textBox.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
    textBox.TextColor3 = Color3.fromRGB(180, 220, 180)
    textBox.Font = Enum.Font.Code
    textBox.TextSize = 10
    textBox.MultiLine = true
    textBox.TextWrapped = true
    textBox.ClearTextOnFocus = false
    textBox.Text = jsonStr or ""
    textBox.ZIndex = 102
    local tb_c = Instance.new("UICorner"); tb_c.CornerRadius = UDim.new(0, 4); tb_c.Parent = textBox
    textBox.Parent = dialog

    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "Đóng"
    closeBtn.Size = UDim2.new(0, 80, 0, 26)
    closeBtn.Position = UDim2.new(1, -88, 0, 260)
    closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    closeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
    closeBtn.Font = Enum.Font.GothamSemibold
    closeBtn.TextSize = 12
    closeBtn.ZIndex = 102
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 4); cc.Parent = closeBtn
    closeBtn.Parent = dialog

    closeBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        if onClose then onClose() end
    end)

    return overlay
end

return ExportImport
