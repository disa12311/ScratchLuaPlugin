--[[
    core/CanvasManager.lua
    Xử lý tương tác trên canvas:
    - trySnap: snap block vào chain, detect container
    - updateMinimap: vẽ lại minimap dots + viewport
    Nhận canvas, minimap, dropZone refs từ init.
--]]

local BlockDefs = require(script.Parent.Parent.blocks.BlockDefinitions)

local CanvasManager = {}

local SNAP_DIST = 28
local CANVAS_W, CANVAS_H = 2000, 2000
local MM_W, MM_H = 110, 80

-- Refs gắn từ init
CanvasManager.canvas      = nil
CanvasManager.canvasArea  = nil
CanvasManager.minimap     = nil
CanvasManager.mmViewport  = nil
CanvasManager.dropZone    = nil
CanvasManager.minimapDots = {}

-- ─── trySnap ─────────────────────────────────────────────────

function CanvasManager.trySnap(movedBd, placedBlocks)
    local mf   = movedBd.frame
    local mPos = mf.AbsolutePosition
    local mSz  = mf.AbsoluteSize
    local best, bestDist, bestSide = nil, SNAP_DIST * 2, nil

    for _, other in ipairs(placedBlocks) do
        if other.id == movedBd.id then continue end
        local of  = other.frame
        local oAP = of.AbsolutePosition
        local oSz = of.AbsoluteSize
        local dx  = math.abs(oAP.X - mPos.X)

        local dBelow = math.abs((oAP.Y + oSz.Y) - mPos.Y) + dx * 0.4
        if dBelow < bestDist and dx < 50 then
            bestDist, best, bestSide = dBelow, other, "below"
        end

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

    -- Container drop zone
    local dz = CanvasManager.dropZone
    if dz then dz.Visible = false end

    if best == nil and dz and CanvasManager.canvas and CanvasManager.canvasArea then
        for _, other in ipairs(placedBlocks) do
            local def = BlockDefs.byId[other.defId]
            if not (def and def.isContainer) then continue end
            local of  = other.frame
            local oAP = of.AbsolutePosition
            local oSz = of.AbsoluteSize
            if mPos.X < oAP.X + oSz.X and mPos.X + mSz.X > oAP.X
            and mPos.Y < oAP.Y + oSz.Y and mPos.Y + mSz.Y > oAP.Y then
                local relX = oAP.X - CanvasManager.canvasArea.AbsolutePosition.X + CanvasManager.canvas.CanvasPosition.X
                local relY = oAP.Y - CanvasManager.canvasArea.AbsolutePosition.Y + CanvasManager.canvas.CanvasPosition.Y
                dz.Position = UDim2.new(0, relX + 8, 0, relY + oSz.Y - 16)
                dz.Size     = UDim2.new(0, oSz.X - 16, 0, 14)
                dz.Visible  = true
                movedBd.parentId = other.id
                break
            end
        end
    end
end

-- ─── updateMinimap ────────────────────────────────────────────

function CanvasManager.updateMinimap(placedBlocks)
    local mm = CanvasManager.minimap
    local mmvp = CanvasManager.mmViewport
    if not mm or not mmvp then return end

    -- Xóa dots cũ
    for _, d in ipairs(CanvasManager.minimapDots) do d:Destroy() end
    CanvasManager.minimapDots = {}

    for _, bd in ipairs(placedBlocks) do
        if not bd.frame then continue end
        local px = bd.frame.Position.X.Offset
        local py = bd.frame.Position.Y.Offset
        local def = BlockDefs.byId[bd.defId]

        local dot = Instance.new("Frame")
        dot.Size  = UDim2.new(0, 8, 0, 5)
        dot.Position = UDim2.new(
            0, math.clamp((px / CANVAS_W) * MM_W, 0, MM_W - 8),
            0, math.clamp((py / CANVAS_H) * MM_H, 0, MM_H - 5)
        )
        dot.BackgroundColor3 = def and def.color or Color3.fromRGB(150, 150, 150)
        dot.BorderSizePixel  = 0
        dot.ZIndex = 31
        local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 2); dc.Parent = dot
        dot.Parent = mm
        table.insert(CanvasManager.minimapDots, dot)
    end

    -- Viewport rect
    local canvas = CanvasManager.canvas
    local area   = CanvasManager.canvasArea
    if canvas and area then
        local vx = (canvas.CanvasPosition.X / CANVAS_W) * MM_W
        local vy = (canvas.CanvasPosition.Y / CANVAS_H) * MM_H
        local vw = (area.AbsoluteSize.X / CANVAS_W) * MM_W
        local vh = (area.AbsoluteSize.Y / CANVAS_H) * MM_H
        mmvp.Size     = UDim2.new(0, math.max(vw, 10), 0, math.max(vh, 8))
        mmvp.Position = UDim2.new(0, math.clamp(vx, 0, MM_W - 10), 0, math.clamp(vy, 0, MM_H - 8))
    end
end

return CanvasManager
