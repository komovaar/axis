local PLAYER = FindMetaTable("Player")

---@param id string
---@return boolean
function PLAYER:ChangeTeam(id)
    local data = axis.team.Get(id)
    if not data then return false end
    if not self then return false end
    self:SetTeam(data.index)
    self:KillSilent()
    self:Spawn()

    return true
end

---@param ply Player
---@return boolean
function GM:PlayerLoadout(ply)
    local data = axis.team.GetByIndex(ply:Team()) or {}

    ply:StripWeapons()
    for _, class in ipairs(data.weapons or {}) do ply:Give(class) end

    return true
end

---@param ply Player
function GM:PlayerSetModel(ply)
    local data = axis.team.GetByIndex(ply:Team())
    if not data then return end
    ply:SetModel(data.model)
end