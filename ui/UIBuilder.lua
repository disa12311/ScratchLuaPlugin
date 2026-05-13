--[[
    UIBuilder.lua  v2
    Tạo Frame UI cho mỗi block trên canvas.
    Cải tiến:
    - Selection highlight khi click
    - Hat shape rõ hơn
    - Input TextBox sync ngay khi thay đổi
    - Drag attribute-based (DragEnded, DeleteRequested)
--]]

local UserInputService = game:GetService("UserInputService")

local UIBuilder = {}

local function darken(c, f)
    f = f or 0.78
    return Color3.new(c.R*f, c.G*f, c.B*f)
end

local function lighten(c, f)
    f = f or 1.18
    return Color3.new(math.min(c.R*f,1), math.min(c.G*f,1), math.min(c.B*f,1))
end

-- ─── Tạo block frame ─────────────────────────────────────────

function UIBuilder.createBlockFrame(def, blockId, parent)
    local inputCount = def.inputs and #def.inputs or 0
    local totalH     = math.max(def.height or 34, 30 + inputCount * 22)
    local hatExtra   = (def.shape == "hat") and 10 or 0

    -- ── Wrapper (chứa hat + main) ──────────────────────────────
    local wrapper = Instance.new("Frame")
    wrapper.Name  = "Block_" .. blockId
    wrapper.Size  = UDim2.new(0, 210, 0, totalH + hatExtra)
    wrapper.BackgroundTransparency = 1
    wrapper.ZIndex = 5
    wrapper.Active = true

    -- ── Hat bump ──────────────────────────────────────────────
    if def.shape == "hat" then
        local hat = Instance.new("Frame")
        hat.Name  = "Hat"
        hat.Size  = UDim2.new(0, 56, 0, 14)
        hat.Position = UDim2.new(0, 12, 0, 0)
        hat.BackgroundColor3 = darken(def.color, 0.85)
        hat.BorderSizePixel  = 0
        hat.ZIndex = 5
        local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0.5, 0); hc.Parent = hat
        hat.Parent = wrapper
    end

    -- ── Main body ─────────────────────────────────────────────
    local body = Instance.new("Frame")
    body.Name  = "Body"
    body.Size  = UDim2.new(1, 0, 0, totalH)
    body.Position = UDim2.new(0, 0, 0, hatExtra)
    body.BackgroundColor3 = def.color
    body.BorderSizePixel  = 0
    body.ZIndex = 5
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 7); bc.Parent = body

    -- Drop shadow
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 3, 1, 3)
    shadow.Position = UDim2.new(0, 2, 0, 2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.72
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 4
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 7); sc.Parent = shadow
    shadow.Parent = wrapper

    -- Border stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color     = darken(def.color, 0.65)
    stroke.Thickness = 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = body

    -- Top connector notch (không cho hat)
    if def.shape ~= "hat" then
        local notch = Instance.new("Frame")
        notch.Size  = UDim2.new(0, 28, 0, 5)
        notch.Position = UDim2.new(0, 16, 0, -2)
        notch.BackgroundColor3 = darken(def.color, 0.75)
        notch.BorderSizePixel  = 0
        notch.ZIndex = 6
        local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0, 3); nc.Parent = notch
        notch.Parent = body
    end

    -- Bottom connector notch (không cho cap)
    if def.shape ~= "cap" then
        local notch = Instance.new("Frame")
        notch.Size  = UDim2.new(0, 28, 0, 5)
        notch.Position = UDim2.new(0, 16, 1, -3)
        notch.BackgroundColor3 = darken(def.color, 0.75)
        notch.BorderSizePixel  = 0
        notch.ZIndex = 6
        local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0, 3); nc.Parent = notch
        notch.Parent = body
    end

    -- ── Label ─────────────────────────────────────────────────
    local textColor = Color3.fromRGB(255, 255, 255)
    local lum = 0.299*def.color.R + 0.587*def.color.G + 0.114*def.color.B
    if lum > 0.72 then textColor = Color3.fromRGB(30, 30, 30) end

    local labelText = def.label:gsub("%[(.-)%]", function(name)
        return "[ " .. name .. " ]"
    end)
    labelText = labelText:match("^%s*(.-)%s*$"):sub(1, 36)

    local lbl = Instance.new("TextLabel")
    lbl.Text    = labelText
    lbl.Size    = UDim2.new(1, -28, 0, 18)
    lbl.Position = UDim2.new(0, 7, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = textColor
    lbl.Font   = Enum.Font.GothamSemibold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.ZIndex = 7
    lbl.Parent = body

    -- ── Input fields ──────────────────────────────────────────
    if def.inputs and #def.inputs > 0 then
        local inputContainer = Instance.new("Frame")
        inputContainer.Name = "Inputs"
        inputContainer.Size = UDim2.new(1, -8, 0, inputCount * 22)
        inputContainer.Position = UDim2.new(0, 4, 0, 20)
        inputContainer.BackgroundTransparency = 1
        inputContainer.ZIndex = 7
        inputContainer.Parent = body

        local il = Instance.new("UIListLayout")
        il.Padding = UDim.new(0, 2)
        il.SortOrder = Enum.SortOrder.LayoutOrder
        il.Parent = inputContainer

        for i, inp in ipairs(def.inputs) do
            local row = Instance.new("Frame")
            row.Name = "InputRow_" .. inp.name
            row.Size = UDim2.new(1, 0, 0, 20)
            row.BackgroundTransparency = 1
            row.LayoutOrder = i
            row.ZIndex = 7
            row.Parent = inputContainer

            local inpLbl = Instance.new("TextLabel")
            inpLbl.Text = inp.label .. ":"
            inpLbl.Size = UDim2.new(0, 50, 1, 0)
            inpLbl.BackgroundTransparency = 1
            inpLbl.TextColor3 = Color3.new(textColor.R, textColor.G, textColor.B)
            inpLbl.TextTransparency = 0.25
            inpLbl.Font = Enum.Font.Gotham
            inpLbl.TextSize = 9
            inpLbl.TextXAlignment = Enum.TextXAlignment.Right
            inpLbl.ZIndex = 8
            inpLbl.Parent = row

            local box = Instance.new("TextBox")
            box.Name = "Input_" .. inp.name
            box.Text = tostring(inp.default or "")
            box.Size = UDim2.new(1, -56, 1, -2)
            box.Position = UDim2.new(0, 52, 0, 1)
            box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            box.BackgroundTransparency = 0.12
            box.TextColor3 = Color3.fromRGB(25, 25, 25)
            box.Font = Enum.Font.Code
            box.TextSize = 9
            box.ClearTextOnFocus = false
            box.PlaceholderText = tostring(inp.default or "")
            box.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
            box.ZIndex = 9
            local bcc = Instance.new("UICorner"); bcc.CornerRadius = UDim.new(0, 3); bcc.Parent = box
            box.Parent = row
        end
    end

    -- ── Delete button ─────────────────────────────────────────
    local delBtn = Instance.new("TextButton")
    delBtn.Name  = "DeleteBtn"
    delBtn.Text  = "×"
    delBtn.Size  = UDim2.new(0, 15, 0, 15)
    delBtn.Position = UDim2.new(1, -17, 0, 3)
    delBtn.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
    delBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    delBtn.Font  = Enum.Font.GothamBold
    delBtn.TextSize = 11
    delBtn.Visible = false
    delBtn.ZIndex = 10
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0.5, 0); dc.Parent = delBtn
    delBtn.Parent = body

    delBtn.MouseButton1Click:Connect(function()
        wrapper:SetAttribute("DeleteRequested", true)
    end)

    body.Parent = wrapper

    -- ── DRAG HANDLER ─────────────────────────────────────────

    local dragging   = false
    local dragStartM = Vector2.zero
    local dragStartP = UDim2.new()

    body.MouseEnter:Connect(function()
        delBtn.Visible = true
        stroke.Color   = lighten(def.color, 1.3)
        stroke.Thickness = 2
    end)
    body.MouseLeave:Connect(function()
        if not dragging then
            delBtn.Visible = false
            stroke.Color   = darken(def.color, 0.65)
            stroke.Thickness = 1.5
        end
    end)

    body.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local focused = UserInputService:GetFocusedTextBox()
        if focused and focused:IsDescendantOf(wrapper) then return end

        dragging    = true
        dragStartM  = Vector2.new(input.Position.X, input.Position.Y)
        dragStartP  = wrapper.Position
        wrapper.ZIndex = 25
        shadow.BackgroundTransparency = 0.45
    end)

    body.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = Vector2.new(input.Position.X - dragStartM.X, input.Position.Y - dragStartM.Y)
            wrapper.Position = UDim2.new(
                dragStartP.X.Scale, dragStartP.X.Offset + d.X,
                dragStartP.Y.Scale, dragStartP.Y.Offset + d.Y
            )
        end
    end)

    body.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            wrapper.ZIndex = 5
            shadow.BackgroundTransparency = 0.72
            delBtn.Visible = false
            stroke.Color   = darken(def.color, 0.65)
            stroke.Thickness = 1.5
            wrapper:SetAttribute("DragEnded", true)
        end
    end)

    wrapper.Parent = parent
    return wrapper
end

return UIBuilder
