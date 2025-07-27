-- WaypointTest_NavNode.lua
-- local _, WPT = ...

---@class NavNode
---@field getLocation fun(): Location
---@field isDynamic boolean
---@field key NavKey
---@field edges NavEdge[]
---@field tempEdges NavEdge[]

local NavNode = {}
WPT.NavNode = NavNode

---Create a deterministic key from mapId and position,
---quantizing to a fixed number of decimal places.
---@param mapId    number
---@param pos      Vec3         # { x:number, y:number, z:number }
---@param precision? number        # how many decimal places to keep; default = 4
---@return NavKey
function NavNode.makeNavKey(mapId, pos, precision)
    precision = precision or 4           -- default to 4 decimal places
    local scale = 10 ^ precision        -- e.g. 10⁴ = 10000

    -- multiply & round to nearest integer
    local xi = math.floor(pos.x * scale + 0.5)
    local yi = math.floor(pos.y * scale + 0.5)
    local zi = math.floor(pos.z + 0.5)

    -- string‑format your final key
    return string.format("%d:%d:%d:%d", mapId, xi, yi, zi)
end

---Construct a new NavNode
---@param mapId number
---@param pos Vec3
---@param edges? NavEdge[]
---@return NavNode
function NavNode.create(mapId, pos, isUI, edges)
    local key = NavNode.makeNavKey(mapId, pos)
    local loc = { mapId = mapId, pos = pos, isUI = isUI }
    local self = setmetatable({
        getLocation = function() return loc end,
        isDynamic = false,
        mapId = mapId,
        pos   = pos,
        key   = key,
        edges = edges or {},
        tempEdges = {}
    }, NavNode)
    return self
end

---Construct a new NavNode
---@param getLoc fun(): Location
---@param suffix string
---@param edges? NavEdge[]
---@return NavNode
function NavNode.createDynamic(getLoc, suffix, edges)
    local key = "dynamic:" .. suffix
    local self = setmetatable({
        getLocation = getLoc,
        isDynamic = true,
        key   = key,
        edges = edges or {},
        tempEdges = {}
    }, NavNode)
    return self
end

--- @param self NavNode The navigation node instance.
--- @return fun():NavEdge Iterator function that yields NavEdge objects.
function NavNode.iterateAllEdges(self)
    -- Iterate edges and temp edges
    return coroutine.wrap(function()
        if self.edges then
            for _, edge in ipairs(self.edges) do
                coroutine.yield(edge)
            end
        end
        if self.tempEdges then
            for _, tempEdge in ipairs(self.tempEdges) do
                coroutine.yield(tempEdge)
            end
        end
    end)
end

return NavNode
