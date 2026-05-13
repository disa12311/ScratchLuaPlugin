--[[
    ui/SidebarManager.lua
    Quản lý sidebar:
    - populateSidebar(filter): render categories + block buttons
    - Hat notch visual, hover effect
    - Custom block: icon ✏, right-click → edit dialog
    Deps: BlockDefs, CustomBlocks (refs gắn từ init)
--]]

local SidebarManager = {}

-- Refs gắn từ init
SidebarManager.sidebar         = nil   -- ScrollingFrame
SidebarManager.BlockDefs       = nil
SidebarManager.CustomBlocks    = nil
SidebarManager.customBlockList = nil   -- ref tới table trong init
SidebarManager.root            = nil   -- root Frame để parent dialogs
SidebarManager.searchBox       = nil
SidebarManager.onBlockClick    = nil   -- fn(def) → placeBlock

-- ─── populate ────────────────────────────────────────────────

function SidebarManager.populate(filter)
    local sidebar   = SidebarManager.sidebar
    local BlockDefs = SidebarManager.BlockDefs
    if not sidebar or not BlockDefs then return end

    filter = filter and filter:lower() or ""

    -- Xóa items cũ
    for _, c in ipairs(sidebar:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    local order = 0

    for _, cat in ipairs(BlockDefs.categories) do
        local matching = {}
        for _, def in ipairs(cat.blocks) do
            if filter == "" or def.label:lower():find(filter, 1, true) then
                table.insert(matching, def)
            end
        end
        if #matching == 0 then continue end

        -- Category header
        local hdr = Instance.new("TextLabel")
        hdr.Text  = cat.label
        hdr.Size  = UDim2.new(1, 0, 0, 18)
        hdr.BackgroundColor3 = cat.color
        hdr.TextColor3 = Color3.fromRGB(255, 255, 255)
        hdr.Font  = Enum.Font.GothamBold
        hdr.TextSize = 10
        hdr.LayoutOrder = order; order += 1
        local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 3); hc.Parent = hdr
        hdr.Parent = sidebar

        for _, def in ipairs(matching) do
            local btn = Instance.new("TextButton")
            btn.Text  = def.label:gsub("%[.-%]", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
            btn.Size  = UDim2.new(1, 0, 0, 28)
            btn.BackgroundColor3 = def.color
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font  = Enum.Font.GothamSemibold
            btn.TextSize = 10
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            btn.AutoButtonColor = false
            btn.LayoutOrder = order; order += 1
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 5); bc.Parent = btn

            -- Hat notch
            if def.shape == "hat" then
                local hn = Instance.new("Frame")
                hn.Size  = UDim2.new(0, 40, 0, 7)
                hn.Position = UDim2.new(0, 6, 0, -4)
                hn.BackgroundColor3 = def.color
                hn.BorderSizePixel  = 0
                hn.ZIndex = 2
                local hnc = Instance.new("UICorner"); hnc.CornerRadius = UDim.new(0, 5); hnc.Parent = hn
                hn.Parent = btn
            end

            -- Hover
            btn.MouseEnter:Connect(function()
                btn.BackgroundColor3 = Color3.new(
                    math.min(def.color.R * 1.15, 1),
                    math.min(def.color.G * 1.15, 1),
                    math.min(def.color.B * 1.15, 1)
                )
            end)
            btn.MouseLeave:Connect(function()
                btn.BackgroundColor3 = def.color
            end)

            -- Click → place
            btn.MouseButton1Click:Connect(function()
                if SidebarManager.onBlockClick then
                    SidebarManager.onBlockClick(def)
                end
            end)

            -- Custom block: ✏ icon + right-click to edit
            if def._isCustom then
                local editDot = Instance.new("TextLabel")
                editDot.Text  = "✏"
                editDot.Size  = UDim2.new(0, 16, 0, 16)
                editDot.Position = UDim2.new(1, -18, 0.5, -8)
                editDot.BackgroundTransparency = 1
                editDot.TextColor3 = Color3.fromRGB(255, 255, 255)
                editDot.TextTransparency = 0.4
                editDot.Font  = Enum.Font.Gotham
                editDot.TextSize = 11
                editDot.ZIndex = 3
                editDot.Parent = btn

                btn.MouseButton2Click:Connect(function()
                    local CB  = SidebarManager.CustomBlocks
                    local CBL = SidebarManager.customBlockList
                    if not CB or not CBL then return end

                    local rawCb
                    for _, cb in ipairs(CBL) do
                        if "custom_" .. cb.id == def.id then rawCb = cb; break end
                    end
                    if not rawCb then return end

                    local dialog = CB.createDialog(rawCb,
                        function(updated)   -- onSave
                            for i, cb in ipairs(CBL) do
                                if cb.id == updated.id then CBL[i] = updated; break end
                            end
                            CB.save(SidebarManager._plugin, CBL)
                            CB.inject(SidebarManager.BlockDefs, CBL)
                            SidebarManager.populate(SidebarManager.searchBox and SidebarManager.searchBox.Text)
                        end,
                        function(cbId)      -- onDelete
                            for i, cb in ipairs(CBL) do
                                if cb.id == cbId then table.remove(CBL, i); break end
                            end
                            CB.save(SidebarManager._plugin, CBL)
                            CB.inject(SidebarManager.BlockDefs, CBL)
                            SidebarManager.populate(SidebarManager.searchBox and SidebarManager.searchBox.Text)
                        end,
                        nil
                    )
                    if SidebarManager.root then dialog.Parent = SidebarManager.root end
                end)
            end

            btn.Parent = sidebar
        end
    end
end

return SidebarManager
