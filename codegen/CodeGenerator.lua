--[[
    CodeGenerator.lua  v2
    Chuyển block chain → Luau code hoàn chỉnh.
    Cải tiến:
    - Xử lý đúng container blocks với nội dung bên trong (parentId)
    - Indent theo cấp độ
    - Syntax highlight RichText
--]]

local BlockDefs = require(script.Parent.Parent.blocks.BlockDefinitions)
local CodeGenerator = {}

local TAB = "\t"

-- ─── Thay thế {placeholder} trong template ───────────────────
local function fill(template, inputs)
    if not template then return "" end
    return (template:gsub("{([%w_]+)}", function(k)
        local v = inputs[k]
        if v ~= nil then return tostring(v) end
        -- Fallback: tạo safe identifier từ k
        return k
    end))
end

-- ─── Indent string ────────────────────────────────────────────
local function indent(code, level)
    if code == "" then return "" end
    local pfx = string.rep(TAB, level)
    local lines = {}
    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line ~= "" and (pfx .. line) or "")
    end
    -- Bỏ newline cuối thừa
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end
    return table.concat(lines, "\n")
end

-- ─── Tìm inner blocks của một container (theo parentId) ───────
local function getChildren(parentId, allBlocks)
    local children = {}
    for _, bd in ipairs(allBlocks) do
        if bd.parentId == parentId and not bd.prev then
            -- Chỉ lấy root của chain con
            table.insert(children, bd)
        end
    end
    -- Sort theo Y position
    table.sort(children, function(a, b)
        local ya = a.frame and a.frame.AbsolutePosition.Y or 0
        local yb = b.frame and b.frame.AbsolutePosition.Y or 0
        return ya < yb
    end)
    return children
end

-- ─── Generate một block + chain tiếp theo ────────────────────
local function genBlock(bd, allBlocks, level, visited)
    visited = visited or {}
    if visited[bd.id] then return "" end
    visited[bd.id] = true

    local def = BlockDefs.byId[bd.defId]
    if not def then return indent("-- [unknown: " .. bd.defId .. "]", level) end

    local pfx  = string.rep(TAB, level)
    local lines = {}

    local mainLine = fill(def.codeTemplate or "", bd.inputs)

    if def.isContainer then
        -- ── Container block ────────────────────────────────────
        -- Thêm dòng mở
        for ln in (mainLine .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, pfx .. ln)
        end

        -- Nội dung bên trong
        local inner = getChildren(bd.id, allBlocks)
        if #inner > 0 then
            for _, child in ipairs(inner) do
                local childCode = genBlock(child, allBlocks, level + 1, visited)
                if childCode ~= "" then
                    table.insert(lines, childCode)
                end
            end
        else
            table.insert(lines, pfx .. TAB .. "-- ...")
        end

        -- Mid template (else)
        if def.midTemplate then
            table.insert(lines, pfx .. def.midTemplate)
            table.insert(lines, pfx .. TAB .. "-- ...")
        end

        -- Close template
        if def.closeTemplate then
            for ln in (def.closeTemplate .. "\n"):gmatch("([^\n]*)\n") do
                if ln ~= "" then table.insert(lines, pfx .. ln) end
            end
        end
    else
        -- ── Thường / stack block ───────────────────────────────
        for ln in (mainLine .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, pfx .. ln)
        end
    end

    local result = table.concat(lines, "\n")

    -- Tiếp tục chain (next)
    if bd.next and not visited[bd.next.id] then
        local nextCode = genBlock(bd.next, allBlocks, level, visited)
        if nextCode ~= "" then
            result = result .. "\n" .. nextCode
        end
    end

    return result
end

-- ─── Public: generate từ list root blocks ─────────────────────
function CodeGenerator.generate(rootBlocks, allBlocks)
    if not rootBlocks or #rootBlocks == 0 then
        return "-- Chưa có block nào"
    end

    local sections = {}
    for _, root in ipairs(rootBlocks) do
        if not root.parentId then   -- chỉ render top-level roots
            local code = genBlock(root, allBlocks, 0, {})
            if code ~= "" then
                table.insert(sections, code)
            end
        end
    end

    return #sections > 0 and table.concat(sections, "\n\n") or "-- Chưa có block nào"
end

-- ─── Syntax highlight cho RichText ───────────────────────────

local KW = {
    ["local"]=1,["function"]=1,["end"]=1,["if"]=1,["then"]=1,
    ["else"]=1,["elseif"]=1,["for"]=1,["do"]=1,["while"]=1,
    ["repeat"]=1,["until"]=1,["return"]=1,["break"]=1,["not"]=1,
    ["and"]=1,["or"]=1,["true"]=1,["false"]=1,["nil"]=1,["in"]=1,
    ["continue"]=1,
}

local function esc(s)
    return s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
end

function CodeGenerator.highlight(code)
    if not code or code == "" then
        return '<font color="#555">-- Chưa có block nào</font>'
    end

    local out = {}
    local lineCount = 0

    for line in (code .. "\n"):gmatch("([^\n]*)\n") do
        lineCount += 1
        if lineCount > 300 then
            table.insert(out, '<font color="#666">... (thêm ' .. (lineCount-300) .. '+ dòng)</font>')
            break
        end

        local e = esc(line)

        -- Comment
        if e:match("^%s*%-%-") then
            table.insert(out, '<font color="#6A9955">' .. e .. '</font>')
            goto continue
        end

        -- String literals " "
        e = e:gsub('(&quot;[^&]*&quot;)', '<font color="#CE9178">%1</font>')
        e = e:gsub("('([^']*)')", '<font color="#CE9178">%1</font>')

        -- Numbers
        e = e:gsub("(%f[%d]%d[%d%.]*)", '<font color="#B5CEA8">%1</font>')

        -- Keywords
        e = e:gsub("([%a_][%w_]*)", function(w)
            if KW[w] then return '<font color="#569CD6">' .. w .. '</font>' end
            return w
        end)

        -- game:GetService highlight
        e = e:gsub("game:GetService", '<font color="#DCDCAA">game:GetService</font>')

        table.insert(out, e)
        ::continue::
    end

    return table.concat(out, "\n")
end

return CodeGenerator
