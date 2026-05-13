--[[
    PersistenceManager.lua
    Lưu và tải layout blocks qua plugin:GetSetting / SetSetting.

    Dữ liệu lưu là JSON string gồm:
    - version: string
    - blockCounter: number
    - blocks: array of { id, defId, posX, posY, inputs, nextId, prevId, parentId }
--]]

local HttpService = game:GetService("HttpService")

local PersistenceManager = {}

local SAVE_KEY     = "ScratchLua_Layout_v2"
local VERSION      = "2.0"

-- ─── Serialize State → JSON string ───────────────────────────

function PersistenceManager.save(plugin, placedBlocks, blockCounter)
    local serialized = {
        version      = VERSION,
        blockCounter = blockCounter,
        blocks       = {},
    }

    for _, bd in ipairs(placedBlocks) do
        -- Đọc giá trị inputs thực tế từ TextBox trên frame
        local inputs = {}
        if bd.frame then
            local inputsFrame = bd.frame:FindFirstChild("Inputs")
            if inputsFrame then
                for _, row in ipairs(inputsFrame:GetChildren()) do
                    if row:IsA("Frame") then
                        for _, child in ipairs(row:GetChildren()) do
                            if child:IsA("TextBox") then
                                -- Tên TextBox là "Input_<name>"
                                local name = child.Name:gsub("^Input_", "")
                                inputs[name] = child.Text
                            end
                        end
                    end
                end
            end
        end
        -- Fallback về inputs đã lưu trong state
        for k, v in pairs(bd.inputs or {}) do
            if inputs[k] == nil then inputs[k] = v end
        end

        local entry = {
            id       = bd.id,
            defId    = bd.defId,
            posX     = bd.frame and bd.frame.Position.X.Offset or 60,
            posY     = bd.frame and bd.frame.Position.Y.Offset or 60,
            inputs   = inputs,
            nextId   = bd.next and bd.next.id or nil,
            prevId   = bd.prev and bd.prev.id or nil,
            parentId = bd.parentId or nil,
        }
        table.insert(serialized.blocks, entry)
    end

    local ok, json = pcall(function()
        return HttpService:JSONEncode(serialized)
    end)

    if ok then
        plugin:SetSetting(SAVE_KEY, json)
        return true
    else
        warn("[ScratchLua] Lỗi khi lưu layout:", json)
        return false
    end
end

-- ─── Deserialize JSON string → raw block table ────────────────

function PersistenceManager.load(plugin)
    local json = plugin:GetSetting(SAVE_KEY)
    if not json or json == "" then return nil end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(json)
    end)

    if not ok or type(data) ~= "table" then
        warn("[ScratchLua] Dữ liệu lưu bị lỗi, bỏ qua.")
        return nil
    end

    if data.version ~= VERSION then
        warn("[ScratchLua] Version layout không khớp, reset.")
        return nil
    end

    return data  -- { version, blockCounter, blocks[] }
end

-- ─── Xóa dữ liệu đã lưu ──────────────────────────────────────

function PersistenceManager.clear(plugin)
    plugin:SetSetting(SAVE_KEY, "")
end

return PersistenceManager
