axis.privilege = axis.privilege or {}

--- Staff privileges, answered by whatever admin mod is installed via CAMI.
--- Deliberately separate from rank permissions (core/sh_rank.lua), which are the
--- in-character authority a Sergeant has over a Private.
axis.privilege.list = {
    { Name = "Axis - Edit Spawnpoints", MinAccess = "admin",
      Description = "Place and remove faction spawnpoints and jail cells." },
    { Name = "Axis - Manage Characters", MinAccess = "admin",
      Description = "Set another player's faction, class or rank." },
    { Name = "Axis - Jail", MinAccess = "admin",
      Description = "Arrest and release players regardless of in-character rank." },
}

for _, privilege in ipairs(axis.privilege.list) do
    CAMI.RegisterPrivilege(privilege)
end

--- Thin wrapper so callers do not have to remember CAMI's argument order.
---@param ply Player
---@param privilegeName string
---@param callback fun(hasAccess: boolean, reason: string?)
---@param target Player?
function axis.HasPrivilege(ply, privilegeName, callback, target)
    CAMI.PlayerHasAccess(ply, privilegeName, callback, target)
end
