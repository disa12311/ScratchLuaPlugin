--[[
    RuntimeErrorTracker.lua
    Phân tích lỗi runtime từ Output/ScriptContext và map về block.

    Cơ chế:
    1. Mỗi block khi generate code được thêm comment marker:
       --[[@BLOCK:blockId:lineNum]]
    2. Khi ScriptContext.Error fires, parse error message lấy line number
    3. Map line number → blockId qua marker table
    4. Highlight frame của block đó màu đỏ

    API:
        RuntimeErrorTracker.annotate(code, placedBlocks)
            → annotatedCode (string), lineMap (table: lineNum→blockId)
        RuntimeErrorTracker.highlightBlock(blockId, placedBlocks, active)
        RuntimeErrorTracker.clearAll(placedBlocks)
        RuntimeErrorTracker.parseErrorLine(errMsg) → lineNum | nil
--]]

local RuntimeErrorTracker = {}

-- ─── Thêm marker vào mỗi line của generated code ─────────────
-- Trả về annotated code và lineMap

function RuntimeErrorTracker.annotate(code, placedBlocks)
    if not code or code == "" then return code, {} end

    -- Build blockId → approximate line range từ code
    -- Simple approach: inject --[[@BLOCK:id]] comment trước mỗi block section
    -- CodeGenerator đã generate code dạng chuỗi, ta split và tìm block bắt đầu

    -- lineMap: lineNumber (1-based) → blockId
    local lineMap = {}
    local lines   = {}
    local lineNum = 1

    -- Chia code thành dòng
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
    end

    -- Map đơn giản: phân tích nội dung code theo pattern từ BlockDefs
    -- Tìm các dòng có pattern của từng block và map về blockId
    -- Đây là best-effort mapping
    local BlockDefs = require(script.Parent.Parent.blocks.BlockDefinitions)

    for lineIdx, line in ipairs(lines) do
        for _, bd in ipairs(placedBlocks) do
            local def = BlockDefs.byId[bd.defId]
            if def and def.codeTemplate then
                -- Lấy 12 ký tự đầu của template để match (sau fill)
                local tmplStart = def.codeTemplate:sub(1, 12)
                    :gsub("{[%w_]+}", ".-")  -- biến {x} thành wildcard
                    :gsub("%(", "%%(")
                    :gsub("%)", "%%)")
                if tmplStart ~= "" and line:match(tmplStart) then
                    lineMap[lineIdx] = bd.id
                    break
                end
            end
        end
    end

    return code, lineMap
end

-- ─── Parse line number từ error message ───────────────────────
-- Formats: "[string]:5: ..." hoặc "Script:5: ..."

function RuntimeErrorTracker.parseErrorLine(errMsg)
    if not errMsg then return nil end
    -- Pattern: :N: (where N is line number)
    local line = errMsg:match(":(%d+):")
    return line and tonumber(line) or nil
end

-- ─── Highlight block frame ────────────────────────────────────

function RuntimeErrorTracker.highlightBlock(blockId, placedBlocks, active)
    for _, bd in ipairs(placedBlocks) do
        if bd.id == blockId and bd.frame then
            local body = bd.frame:FindFirstChild("Body")
            if body then
                local stroke = body:FindFirstChildOfClass("UIStroke")
                if active then
                    -- Đỏ nhấp nháy
                    if stroke then
                        stroke.Color = Color3.fromRGB(255, 60, 60)
                        stroke.Thickness = 3
                    end
                    -- Error badge
                    local badge = body:FindFirstChild("ErrorBadge")
                    if not badge then
                        badge = Instance.new("Frame")
                        badge.Name = "ErrorBadge"
                        badge.Size = UDim2.new(0, 16, 0, 16)
                        badge.Position = UDim2.new(0, 2, 0, 2)
                        badge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
                        badge.ZIndex = 12
                        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.5, 0); bc.Parent = badge
                        local bl = Instance.new("TextLabel")
                        bl.Text = "!"
                        bl.Size = UDim2.new(1, 0, 1, 0)
                        bl.BackgroundTransparency = 1
                        bl.TextColor3 = Color3.fromRGB(255, 255, 255)
                        bl.Font = Enum.Font.GothamBold
                        bl.TextSize = 11
                        bl.ZIndex = 13
                        bl.Parent = badge
                        badge.Parent = body
                    end
                    badge.Visible = true

                    -- Tooltip
                    bd.frame:SetAttribute("HasError", true)
                else
                    if stroke then
                        local def = require(script.Parent.Parent.blocks.BlockDefinitions).byId[bd.defId]
                        stroke.Color = def and Color3.new(def.color.R*0.65, def.color.G*0.65, def.color.B*0.65) or Color3.fromRGB(80,80,80)
                        stroke.Thickness = 1.5
                    end
                    local badge = body:FindFirstChild("ErrorBadge")
                    if badge then badge.Visible = false end
                    bd.frame:SetAttribute("HasError", false)
                end
            end
            break
        end
    end
end

-- ─── Xóa tất cả error highlights ─────────────────────────────

function RuntimeErrorTracker.clearAll(placedBlocks)
    for _, bd in ipairs(placedBlocks) do
        if bd.frame and bd.frame:GetAttribute("HasError") then
            RuntimeErrorTracker.highlightBlock(bd.id, placedBlocks, false)
        end
    end
end

-- ─── Hook vào ScriptContext.Error (chỉ hoạt động trong Play mode) ──
-- Trả về Connection để disconnect sau

function RuntimeErrorTracker.hookScriptContext(placedBlocks, lineMap, onError)
    local ScriptContext = game:GetService("ScriptContext")

    local conn = ScriptContext.Error:Connect(function(message, trace, script)
        local lineNum = RuntimeErrorTracker.parseErrorLine(message)
        if lineNum and lineMap[lineNum] then
            local blockId = lineMap[lineNum]
            RuntimeErrorTracker.highlightBlock(blockId, placedBlocks, true)
            if onError then onError(blockId, message) end
        end
    end)

    return conn
end

return RuntimeErrorTracker
