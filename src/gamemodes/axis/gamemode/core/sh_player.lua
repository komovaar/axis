local PLAYER = FindMetaTable("Player")

--- Player only gains a handle to its character; everything else lives on the
--- character metatable. Nothing here shadows an existing Entity method.
---@return table|nil
function PLAYER:GetCharacter()
    if SERVER then return self.axisChar end

    local id = self:GetNW2Int("axisCharID", 0)
    if id == 0 then return nil end

    return axis.char.loaded[id]
end

---@return boolean
function PLAYER:HasCharacter()
    return self:GetCharacter() ~= nil
end

---@return string|nil
function PLAYER:GetFaction()
    local char = self:GetCharacter()
    return char and char:GetFaction()
end

---@return table|nil
function PLAYER:GetFactionTable()
    local char = self:GetCharacter()
    return char and char:GetFactionTable()
end

---@return string|nil
function PLAYER:GetRank()
    local char = self:GetCharacter()
    return char and char:GetRank()
end

--- Deliberately not named GetClass - Entity:GetClass() already exists and means
--- the entity classname.
---@return string|nil
function PLAYER:GetCharClass()
    local char = self:GetCharacter()
    return char and char:GetClass()
end

--- Falls back to the Steam name so chat and logging never print nil for a player
--- who has not picked a character yet.
---@return string
function PLAYER:GetDisplayName()
    local char = self:GetCharacter()
    return char and char:GetDisplayName() or self:Nick()
end

---@return table
function PLAYER:GetDisplayColor()
    local char = self:GetCharacter()
    return char and char:GetColor() or axis.config.color.default
end

---@param permission string
---@return boolean
function PLAYER:HasPermission(permission)
    return axis.rank.HasPermission(self, permission)
end
